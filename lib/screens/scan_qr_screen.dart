import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ScanQrScreen extends StatefulWidget {
  const ScanQrScreen({super.key});

  @override
  State<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends State<ScanQrScreen> {
  final MobileScannerController controller =
      MobileScannerController();

  final TextEditingController nameController =
      TextEditingController();

  final TextEditingController amountController =
      TextEditingController();

  final TextEditingController noteController =
      TextEditingController();

  bool scanned = false;
  bool processing = false;

  @override
  void dispose() {
    controller.dispose();
    nameController.dispose();
    amountController.dispose();
    noteController.dispose();
    super.dispose();
  }

  // ============================================================
  // QR VALIDATION
  // ============================================================

  String? _extractSessionId(String code) {
    final cleaned = code.trim();

    // Current ChattªX format.
    const currentPrefix = 'CHATTAX://TRANSFER/';

    // Accept older QR codes too.
    const legacyPrefix = 'CHATEX://TRANSFER/';

    if (cleaned.startsWith(currentPrefix)) {
      final sessionId =
          cleaned.substring(currentPrefix.length).trim();

      if (sessionId.isEmpty) return null;

      return sessionId;
    }

    if (cleaned.startsWith(legacyPrefix)) {
      final sessionId =
          cleaned.substring(legacyPrefix.length).trim();

      if (sessionId.isEmpty) return null;

      return sessionId;
    }

    return null;
  }

  // ============================================================
  // PROCESS QR
  // ============================================================

  Future<void> _processQr(String code) async {
    if (processing) return;

    setState(() {
      processing = true;
      scanned = true;
    });

    final sessionId = _extractSessionId(code);

    if (sessionId == null) {
      _showMessage(
        'Not a ChattªX Transfer QR',
        error: true,
      );

      setState(() {
        processing = false;
        scanned = false;
      });

      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage(
        'Please sign in to ChattªX first.',
        error: true,
      );

      setState(() {
        processing = false;
        scanned = false;
      });

      return;
    }

    try {
      final sessionRef = FirebaseFirestore.instance
          .collection('transfer_sessions')
          .doc(sessionId);

      final sessionSnapshot = await sessionRef.get();

      if (!sessionSnapshot.exists) {
        _showMessage(
          'This ChattªX QR session has expired or does not exist.',
          error: true,
        );

        setState(() {
          processing = false;
          scanned = false;
        });

        return;
      }

      final data = sessionSnapshot.data();

      if (data == null) {
        throw Exception('Invalid transfer session.');
      }

      final String senderId =
          (data['senderId'] ?? '').toString();

      final String status =
          (data['status'] ?? 'waiting').toString();

      if (senderId.isEmpty) {
        _showMessage(
          'Invalid ChattªX transfer session.',
          error: true,
        );

        setState(() {
          processing = false;
          scanned = false;
        });

        return;
      }

      // Don't allow the owner to scan their own QR.
      if (senderId == user.uid) {
        _showMessage(
          'You cannot scan your own ChattªX transfer QR.',
          error: true,
        );

        setState(() {
          processing = false;
          scanned = false;
        });

        return;
      }

      if (status == 'completed') {
        _showMessage(
          'This transfer session has already been completed.',
          error: true,
        );

        setState(() {
          processing = false;
          scanned = false;
        });

        return;
      }

      if (status == 'expired') {
        _showMessage(
          'This ChattªX transfer QR has expired.',
          error: true,
        );

        setState(() {
          processing = false;
          scanned = false;
        });

        return;
      }

      // ========================================================
      // GET SCANNER USER INFORMATION
      // ========================================================

      String receiverName = 'ChattªX User';

      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data();

          if (userData != null) {
            receiverName =
                (userData['displayName'] ??
                        userData['name'] ??
                        userData['username'] ??
                        receiverName)
                    .toString();
          }
        }
      } catch (_) {
        // Keep default name if user profile isn't available.
      }

      // ========================================================
      // ATTACH RECEIVER TO SESSION
      // ========================================================

      await sessionRef.update({
        'receiverId': user.uid,
        'receiverName': receiverName,
        'status': 'scanned',
        'scannedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      setState(() {
        processing = false;
      });

      _showTransferSheet(
        sessionId: sessionId,
        senderId: senderId,
        receiverName: receiverName,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        processing = false;
        scanned = false;
      });

      _showMessage(
        'Unable to connect to this ChattªX transfer.',
        error: true,
      );
    }
  }

  // ============================================================
  // TRANSFER SHEET
  // ============================================================

  void _showTransferSheet({
    required String sessionId,
    required String senderId,
    required String receiverName,
  }) {
    nameController.text = receiverName;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF050816),
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(30),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 25,
              bottom:
                  MediaQuery.of(sheetContext).viewInsets.bottom +
                      25,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 50,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius:
                          BorderRadius.circular(10),
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF00D9FF),
                    size: 54,
                  ),

                  const SizedBox(height: 12),

                  const Text(
                    'ChattªX Transfer',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    'Secure transfer session connected',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 14,
                    ),
                  ),

                  const SizedBox(height: 24),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111827),
                      borderRadius:
                          BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFF00D9FF)
                            .withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0x2200D9FF),
                          ),
                          child: const Icon(
                            Icons.person_rounded,
                            color: Color(0xFF00D9FF),
                          ),
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Connected to',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                receiverName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const Icon(
                          Icons.verified_rounded,
                          color: Color(0xFF00D9FF),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  _inputField(
                    controller: amountController,
                    hint: 'Amount',
                    icon: Icons.payments_outlined,
                    keyboard: TextInputType.number,
                  ),

                  const SizedBox(height: 12),

                  _inputField(
                    controller: noteController,
                    hint: 'Message or note',
                    icon: Icons.notes_outlined,
                  ),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor:
                            const Color(0xFF7B2FF7),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(18),
                        ),
                      ),
                      onPressed: () async {
                        await _completeTransfer(
                          sessionId: sessionId,
                          senderId: senderId,
                          receiverName: receiverName,
                          sheetContext: sheetContext,
                        );
                      },
                      child: const Text(
                        'Continue Transfer',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  TextButton(
                    onPressed: () {
                      Navigator.pop(sheetContext);

                      setState(() {
                        scanned = false;
                      });
                    },
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.white54,
                      ),
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
  // COMPLETE TRANSFER
  // ============================================================

  Future<void> _completeTransfer({
    required String sessionId,
    required String senderId,
    required String receiverName,
    required BuildContext sheetContext,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    try {
      final amount = amountController.text.trim();
      final note = noteController.text.trim();

      final sessionRef = FirebaseFirestore.instance
          .collection('transfer_sessions')
          .doc(sessionId);

      final transferRef = FirebaseFirestore.instance
          .collection('transfers')
          .doc();

      final batch =
          FirebaseFirestore.instance.batch();

      batch.set(transferRef, {
        'transferId': transferRef.id,
        'sessionId': sessionId,
        'senderId': senderId,
        'receiverId': user.uid,
        'receiverName': receiverName,
        'amount': amount,
        'note': note,
        'status': 'completed',
        'createdAt': FieldValue.serverTimestamp(),
        'completedAt': FieldValue.serverTimestamp(),
      });

      batch.update(sessionRef, {
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (!mounted) return;

      Navigator.pop(sheetContext);

      _showMessage(
        'ChattªX Transfer completed successfully.',
      );

      setState(() {
        scanned = false;
      });

      amountController.clear();
      noteController.clear();
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Transfer could not be completed.',
        error: true,
      );
    }
  }

  // ============================================================
  // INPUT
  // ============================================================

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboard = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white10,
        ),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        style: const TextStyle(
          color: Colors.white,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            color: Colors.white54,
          ),
          prefixIcon: Icon(
            icon,
            color: const Color(0xFF00D9FF),
          ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.all(16),
        ),
      ),
    );
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(
    String message, {
    bool error = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: error
              ? const Color(0xFFB3261E)
              : const Color(0xFF00AFC7),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
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
      backgroundColor: const Color(0xFF050816),
      body: SafeArea(
        child: Stack(
          children: [
            MobileScanner(
              controller: controller,
              onDetect: (capture) {
                if (scanned || processing) return;

                final barcodes = capture.barcodes;

                if (barcodes.isEmpty) return;

                final code =
                    barcodes.first.rawValue ?? '';

                if (code.isEmpty) return;

                _processQr(code);
              },
            ),

            // Scanner dark overlay.
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: Colors.black.withValues(
                    alpha: 0.35,
                  ),
                ),
              ),
            ),

            // ==================================================
            // TOP BAR
            // ==================================================

            Positioned(
              top: 20,
              left: 20,
              right: 20,
              child: Row(
                children: [
                  _topButton(
                    Icons.arrow_back_rounded,
                    () => Navigator.pop(context),
                  ),

                  Expanded(
                    child: Center(
                      child: RichText(
                        text: const TextSpan(
                          children: [
                            TextSpan(
                              text: 'Chattª',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight:
                                    FontWeight.w900,
                                letterSpacing: -1,
                              ),
                            ),
                            TextSpan(
                              text: 'X',
                              style: TextStyle(
                                color:
                                    Color(0xFFB026FF),
                                fontSize: 32,
                                fontWeight:
                                    FontWeight.w900,
                                letterSpacing: -1.5,
                                shadows: [
                                  Shadow(
                                    color:
                                        Color(0xFFB026FF),
                                    blurRadius: 18,
                                  ),
                                  Shadow(
                                    color:
                                        Color(0xFF7B2FF7),
                                    blurRadius: 30,
                                  ),
                                ],
                              ),
                            ),
                            TextSpan(
                              text: ' Transfer',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  _topButton(
                    Icons.flashlight_on_rounded,
                    () async {
                      await controller.toggleTorch();
                    },
                  ),
                ],
              ),
            ),

            // ==================================================
            // SCANNER FRAME
            // ==================================================

            Center(
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  borderRadius:
                      BorderRadius.circular(28),
                  border: Border.all(
                    color: const Color(0xFF00D9FF),
                    width: 3,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x5500D9FF),
                      blurRadius: 25,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),

            // ==================================================
            // SCANNING MESSAGE
            // ==================================================

            Positioned(
              bottom: 40,
              left: 20,
              right: 20,
              child: Container(
                padding:
                    const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius:
                      BorderRadius.circular(22),
                  border: Border.all(
                    color: Colors.white10,
                  ),
                ),
                child: processing
                    ? const Column(
                        children: [
                          SizedBox(
                            width: 28,
                            height: 28,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color:
                                  Color(0xFF00D9FF),
                            ),
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Connecting to ChattªX transfer...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ],
                      )
                    : const Column(
                        children: [
                          Icon(
                            Icons.qr_code_scanner_rounded,
                            color:
                                Color(0xFF00D9FF),
                            size: 32,
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Scan ChattªX Transfer QR',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Securely connect and transfer instantly.',
                            textAlign:
                                TextAlign.center,
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 13,
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

  Widget _topButton(
    IconData icon,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius:
              BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white10,
          ),
        ),
        child: Icon(
          icon,
          color: Colors.white,
        ),
      ),
    );
  }
}