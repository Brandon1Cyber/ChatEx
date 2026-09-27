import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class VoiceRecorder extends StatefulWidget {
  final VoidCallback onCancel;

  /// Sends:
  ///
  /// path       -> actual recorded audio file
  /// duration   -> actual recorded audio duration
  /// waveform   -> waveform generated from the real recording
  ///
  /// The waveform is NOT decorative/random.
  final Function(
    String path,
    int duration,
    List<double> waveform,
  ) onSend;

  const VoiceRecorder({
    super.key,
    required this.onCancel,
    required this.onSend,
  });

  @override
  State<VoiceRecorder> createState() => _VoiceRecorderState();
}

class _VoiceRecorderState extends State<VoiceRecorder>
    with SingleTickerProviderStateMixin {
  // ============================================================
  // COLORS
  // ============================================================

  static const Color _bgColor = Color(0xFF0B0B14);
  static const Color _borderColor = Color(0xFF8A5CFF);
  static const Color _pink = Color(0xFFFF2D95);
  static const Color _purple = Color(0xFFB026FF);
  static const Color _deepPurple = Color(0xFF6C2BFF);
  static const Color _cyan = Color(0xFF00E5FF);
  static const Color _red = Color(0xFFFF496C);

  // ============================================================
  // RECORDER
  // ============================================================

  final AudioRecorder recorder = AudioRecorder();

  Timer? amplitudeTimer;
  Timer? durationTimer;

  final Stopwatch _recordingStopwatch = Stopwatch();

  // ============================================================
  // RECORDING STATE
  // ============================================================

  bool recording = false;
  bool paused = false;
  bool preview = false;

  /// Used later by MessageBubble for frozen voice notes.
  bool frozen = false;

  String? recordedPath;

  // ============================================================
  // REAL AUDIO DATA
  // ============================================================

  /// Real microphone amplitude samples (raw, one per ~60ms tick).
  final List<double> _rawAmplitudes = [];

  /// Final compressed waveform (fixed length, represents the whole clip).
  List<double> waveform = [];

  /// Number of bars stored with the message.
  static const int waveformBars = 48;

  /// Current real microphone amplitude.
  double currentAmplitude = 0.0;

  // ============================================================
  // VISUAL
  // ============================================================

  late AnimationController pulseController;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    startRecording();
  }

  // ============================================================
  // CURRENT DURATION
  // ============================================================

  int get _durationSeconds => _recordingStopwatch.elapsed.inSeconds;

  // ============================================================
  // START RECORDING
  // ============================================================

  Future<void> startRecording() async {
    try {
      final permission = await recorder.hasPermission();

      if (!permission) {
        debugPrint('ChattªX microphone permission denied.');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Microphone permission is required.'),
            ),
          );
        }

        return;
      }

      final directory = await getTemporaryDirectory();

      final path =
          '${directory.path}/chattax_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: path,
      );

      _rawAmplitudes.clear();
      waveform.clear();

      _recordingStopwatch
        ..reset()
        ..start();

      if (!mounted) return;

      setState(() {
        recording = true;
        paused = false;
        preview = false;
        frozen = false;

        recordedPath = null;
        currentAmplitude = 0.0;
      });

      _startAmplitudeCapture();
      _startDurationRefresh();
    } catch (e) {
      debugPrint('ChattªX start recording error: $e');
    }
  }

  // ============================================================
  // REAL MICROPHONE AMPLITUDE CAPTURE
  // ============================================================

  void _startAmplitudeCapture() {
    amplitudeTimer?.cancel();

    amplitudeTimer = Timer.periodic(
      const Duration(milliseconds: 60),
      (_) async {
        if (!recording || paused) return;

        try {
          final amplitude = await recorder.getAmplitude();

          if (!mounted) return;

          final double db = amplitude.current;

          double normalized;

          if (db.isNaN || db.isInfinite) {
            normalized = 0.0;
          } else {
            /*
             * record package amplitude is measured in dB.
             *
             * Rough visual range:
             *
             * -60 dB = silence
             * -40 dB = quiet
             * -25 dB = normal speech
             * -10 dB = loud
             *  -5 dB = very loud
             */

            normalized = ((db + 60.0) / 60.0).clamp(0.0, 1.0).toDouble();
          }

          // Real silence / noise floor.
          if (normalized < 0.08) {
            normalized = 0.0;
          }

          // Contrast curve.
          if (normalized > 0.0) {
            normalized = math.pow(normalized, 0.72).toDouble().clamp(0.0, 1.0);
          }

          /*
           * This sample belongs to the actual recording.
           * No: sin() / random() / fake waveform.
           */
          _rawAmplitudes.add(normalized);

          // Keep memory bounded during extremely long recordings.
          if (_rawAmplitudes.length > 10000) {
            _rawAmplitudes.removeAt(0);
          }

          setState(() {
            currentAmplitude = normalized;
          });
        } catch (e) {
          debugPrint('ChattªX amplitude capture error: $e');
        }
      },
    );
  }

  // ============================================================
  // DURATION REFRESH
  // ============================================================

  void _startDurationRefresh() {
    durationTimer?.cancel();

    durationTimer = Timer.periodic(
      const Duration(milliseconds: 250),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        if (!recording) {
          timer.cancel();
          return;
        }

        if (!paused) {
          setState(() {});
        }
      },
    );
  }

  // ============================================================
  // PAUSE / RESUME
  // ============================================================

  Future<void> pauseRecording() async {
    if (!recording) return;

    try {
      if (paused) {
        await recorder.resume();

        _recordingStopwatch.start();

        if (!mounted) return;

        setState(() {
          paused = false;
          currentAmplitude = 0.0;
        });
      } else {
        await recorder.pause();

        _recordingStopwatch.stop();

        if (!mounted) return;

        setState(() {
          paused = true;
          currentAmplitude = 0.0;
        });
      }
    } catch (e) {
      debugPrint('ChattªX pause/resume error: $e');
    }
  }

  // ============================================================
  // STOP RECORDING
  // ============================================================

  Future<void> stopRecording() async {
    if (!recording) return;

    try {
      amplitudeTimer?.cancel();
      durationTimer?.cancel();

      _recordingStopwatch.stop();

      final path = await recorder.stop();

      if (path == null || path.isEmpty) {
        debugPrint('ChattªX recorder returned no audio path.');
        return;
      }

      // Compress the ENTIRE recording into a fixed set of bars —
      // this is what gets shown full-width in preview, WhatsApp-style.
      final generatedWaveform = _compressWaveform(_rawAmplitudes, waveformBars);

      final actualDuration = _durationSeconds;

      if (!mounted) return;

      setState(() {
        recordedPath = path;

        recording = false;
        paused = false;
        preview = true;

        currentAmplitude = 0.0;

        waveform = generatedWaveform;
      });

      debugPrint('==========================================');
      debugPrint('ChattªX VOICE RECORDING COMPLETE');
      debugPrint('Duration: ${actualDuration}s');
      debugPrint('Raw samples: ${_rawAmplitudes.length}');
      debugPrint('Waveform bars: ${waveform.length}');
      debugPrint('Frozen: $frozen');
      debugPrint('==========================================');
    } catch (e) {
      debugPrint('ChattªX stop recording error: $e');
    }
  }

  // ============================================================
  // COMPRESS REAL AUDIO INTO FIXED BARS
  // ============================================================

  List<double> _compressWaveform(
  List<double> samples,
  int targetBars,
) {
  if (samples.isEmpty) {
    return List<double>.filled(targetBars, 0.0);
  }

  final result = <double>[];

  for (int bar = 0; bar < targetBars; bar++) {
    final start =
        ((bar / targetBars) * samples.length).floor();

    final end =
        (((bar + 1) / targetBars) * samples.length).ceil();

    final safeStart =
        start.clamp(0, samples.length - 1);

    final safeEnd =
        end.clamp(safeStart + 1, samples.length);

    final section =
        samples.sublist(safeStart, safeEnd);

    if (section.isEmpty) {
      result.add(0.0);
      continue;
    }

    // ------------------------------------------------------------
    // REAL SECTION AMPLITUDE
    // ------------------------------------------------------------

    double peak = 0.0;

    for (final value in section) {
      if (value > peak) {
        peak = value;
      }
    }

    // ------------------------------------------------------------
    // RMS
    // ------------------------------------------------------------

    double sumSquares = 0.0;

    for (final value in section) {
      sumSquares += value * value;
    }

    final rms =
        math.sqrt(sumSquares / section.length);

    // ------------------------------------------------------------
    // Combine RMS + PEAK
    //
    // RMS controls the overall loudness.
    // Peak preserves real speech spikes.
    // ------------------------------------------------------------

    double value =
        (rms * 0.82) +
        (peak * 0.18);

    // ------------------------------------------------------------
    // IMPORTANT:
    // Preserve REAL SILENCE.
    //
    // Previously quiet sections could become large because
    // the RMS/peak combination was too forgiving.
    // ------------------------------------------------------------

    if (peak < 0.075) {
      value = 0.0;
    }

    // Very quiet speech/noise should stay small.
    if (value < 0.10) {
      value *= 0.35;
    }

    // ------------------------------------------------------------
    // Gentle contrast.
    //
    // Do NOT aggressively boost quiet audio.
    // ------------------------------------------------------------

    if (value > 0.0) {
      value = math.pow(
        value,
        1.12,
      ).toDouble();
    }

    result.add(
      value.clamp(0.0, 1.0),
    );
  }

  return result;
}
  // ============================================================
  // CANCEL
  // ============================================================

  Future<void> cancelRecording() async {
    try {
      amplitudeTimer?.cancel();
      durationTimer?.cancel();

      _recordingStopwatch.stop();

      if (recording) {
        await recorder.stop();
      }
    } catch (_) {}

    if (!mounted) return;

    widget.onCancel();
  }

  // ============================================================
  // FREEZE STATE
  //
  // The actual frozen-message interaction will happen inside
  // MessageBubble. This state exists so the recorder is already
  // prepared for voice-note freezing without changing the audio.
  //
  // Freezing a voice note does NOT alter the audio file, waveform,
  // or duration — MessageBubble simply stores/uses `isFrozen`.
  // ============================================================

  void toggleFreeze() {
    if (!preview) return;

    setState(() {
      frozen = !frozen;
    });
  }

  // ============================================================
  // SEND
  // ============================================================

  void sendRecording() {
    if (!preview) {
      stopRecording();
      return;
    }

    if (recordedPath == null) return;

    final duration = _durationSeconds;

    // The exact waveform belonging to this recording is sent with it.
    widget.onSend(
      recordedPath!,
      duration,
      List<double>.from(waveform),
    );
  }

  // ============================================================
  // LIVE SAMPLE WINDOW
  //
  // Returns however many samples fit the given bar count, padding
  // the front with silence so bars fill in from the left like
  // WhatsApp does while you're recording.
  // ============================================================

  List<double> _lastNSamples(int n) {
    if (n <= 0) return const [];

    if (_rawAmplitudes.length >= n) {
      return _rawAmplitudes.sublist(_rawAmplitudes.length - n);
    }

    return [
      ...List<double>.filled(n - _rawAmplitudes.length, 0.0),
      ..._rawAmplitudes,
    ];
  }

  // ============================================================
  // WAVEFORM AREA (overflow-proof: sized from real constraints)
  // ============================================================

  Widget _buildWaveformArea() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        if (width <= 0) return const SizedBox.shrink();

        if (preview) {
          // Show the FULL recording's waveform, scaled to fit exactly.
          return CustomPaint(
            size: Size(width, 44),
            painter: _WaveformPainter(
              amplitudes: waveform.isEmpty
                  ? List<double>.filled(waveformBars, 0.0)
                  : waveform,
            ),
          );
        }

        // Live: pick however many bars comfortably fit this width.
        const double targetSpacing = 6.0;
        final int barCount =
            math.max(10, (width / targetSpacing).floor());

        return CustomPaint(
          size: Size(width, 44),
          painter: _WaveformPainter(
            amplitudes: _lastNSamples(barCount),
          ),
        );
      },
    );
  }

  // ============================================================
  // DURATION DISPLAY
  // ============================================================

  String _formatSeconds(int value) {
    final minutes = value ~/ 60;
    final seconds = value % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final duration = _formatSeconds(_durationSeconds);
    final bool showRecDot = recording && !paused;

    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: _borderColor.withValues(alpha: .35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: _purple.withValues(alpha: .18),
            blurRadius: 22,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ======================================================
          // DELETE
          // ======================================================
          GestureDetector(
            onTap: cancelRecording,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _red.withValues(alpha: .10),
                border: Border.all(color: _red.withValues(alpha: .35)),
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: Color(0xFFFF6684),
                size: 21,
              ),
            ),
          ),

          const SizedBox(width: 8),

          // ======================================================
          // WAVEFORM (flexible, never overflows)
          // ======================================================
          Expanded(child: _buildWaveformArea()),

          const SizedBox(width: 8),

          // ======================================================
          // REC DOT + DURATION
          // ======================================================
          if (showRecDot) ...[
            AnimatedBuilder(
              animation: pulseController,
              builder: (context, _) {
                final opacity = 0.35 + (pulseController.value * 0.65);
                return Container(
                  width: 7,
                  height: 7,
                  margin: const EdgeInsets.only(right: 5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _red.withValues(alpha: opacity),
                    boxShadow: [
                      BoxShadow(
                        color: _red.withValues(alpha: opacity * .6),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                );
              },
            ),
          ],

          Text(
            duration,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(width: 6),

          // ======================================================
          // PAUSE / RESUME
          // ======================================================
          if (!preview)
            GestureDetector(
              onTap: pauseRecording,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _cyan.withValues(alpha: .08),
                  border: Border.all(color: _cyan.withValues(alpha: .30)),
                ),
                child: Icon(
                  paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  color: _cyan,
                  size: 21,
                ),
              ),
            ),

          // ======================================================
          // FREEZE (preview only)
          //
          // The actual frozen voice-note behavior is handled by
          // MessageBubble after the message is sent.
          // ======================================================
          if (preview) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: toggleFreeze,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: frozen
                      ? _cyan.withValues(alpha: .16)
                      : _purple.withValues(alpha: .10),
                  border: Border.all(
                    color: frozen
                        ? _cyan
                        : _purple.withValues(alpha: .45),
                  ),
                  boxShadow: frozen
                      ? [
                          BoxShadow(
                            color: _cyan.withValues(alpha: .27),
                            blurRadius: 10,
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  frozen ? Icons.lock_rounded : Icons.ac_unit_rounded,
                  color: frozen ? _cyan : const Color(0xFFC78CFF),
                  size: 19,
                ),
              ),
            ),
          ],

          const SizedBox(width: 6),

          // ======================================================
          // STOP / SEND
          // ======================================================
          GestureDetector(
            onTap: sendRecording,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_purple, _deepPurple],
                ),
                boxShadow: [
                  BoxShadow(
                    color: _purple.withValues(alpha: .30),
                    blurRadius: 13,
                  ),
                ],
              ),
              child: Icon(
                preview ? Icons.send_rounded : Icons.stop_rounded,
                color: Colors.white,
                size: 21,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    amplitudeTimer?.cancel();
    durationTimer?.cancel();

    _recordingStopwatch.stop();

    pulseController.dispose();

    recorder.dispose();

    super.dispose();
  }
}

// ============================================================
// WAVEFORM PAINTER
//
// Renders bars sized purely from the given canvas Size — this is
// the piece that makes overflow structurally impossible: bar width
// and gap are always derived from the real available width, never
// from a fixed pixel value.
// ============================================================

class _WaveformPainter extends CustomPainter {
  final List<double> amplitudes;

  const _WaveformPainter({
    required this.amplitudes,
  });

  static const List<Color> _gradientColors = [
    Color(0xFFFF2D95),
    Color(0xFFB026FF),
    Color(0xFF00E5FF),
  ];

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    if (amplitudes.isEmpty ||
        size.width <= 0 ||
        size.height <= 0) {
      return;
    }

    final int barCount = amplitudes.length;

    // ------------------------------------------------------------
    // SPACING
    //
    // The important change:
    // bars are now much thinner than their available slot.
    //
    // This creates visible space between every waveform line.
    // ------------------------------------------------------------

    final double slot =
        size.width / barCount;

    final double barWidth =
        math.min(
          1.8,
          slot * 0.28,
        );

    final double centerY =
        size.height / 2;

    // ------------------------------------------------------------
    // FULL WIDTH GRADIENT
    // ------------------------------------------------------------

    final shader =
        const LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: _gradientColors,
    ).createShader(
      Rect.fromLTWH(
        0,
        0,
        size.width,
        size.height,
      ),
    );

    // ------------------------------------------------------------
    // MAIN BAR
    // ------------------------------------------------------------

    final barPaint = Paint()
      ..shader = shader
      ..style = PaintingStyle.fill;

    // ------------------------------------------------------------
    // SOFT GLOW
    // ------------------------------------------------------------

    final glowPaint = Paint()
      ..shader = shader
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(
        BlurStyle.normal,
        4,
      );

    // ------------------------------------------------------------
    // DRAW EVERY REAL SAMPLE
    // ------------------------------------------------------------

    for (int i = 0; i < barCount; i++) {
      final double amp =
          amplitudes[i]
              .clamp(0.0, 1.0)
              .toDouble();

      // ----------------------------------------------------------
      // TRUE SILENCE
      //
      // Silence should look like a tiny line, NOT a big bar.
      // ----------------------------------------------------------

      double barHeight;

      if (amp <= 0.015) {
        barHeight = 1.5;
      } else if (amp <= 0.05) {
        barHeight = 2.5;
      } else if (amp <= 0.10) {
        barHeight = 4.0;
      } else {
        // Real amplitude controls the height.
        barHeight =
            3.0 +
            (amp * (size.height - 3.0));
      }

      barHeight = barHeight.clamp(
        1.5,
        size.height,
      );

      // ----------------------------------------------------------
      // CENTER BAR IN ITS SLOT
      // ----------------------------------------------------------

      final double x =
          (i * slot) +
          (slot / 2) -
          (barWidth / 2);

      final rect = Rect.fromLTWH(
        x,
        centerY - (barHeight / 2),
        barWidth,
        barHeight,
      );

      final rrect =
          RRect.fromRectAndRadius(
        rect,
        Radius.circular(
          barWidth,
        ),
      );

      // ----------------------------------------------------------
      // GLOW ONLY ON ACTUAL LOUD AUDIO
      // ----------------------------------------------------------

      if (amp > 0.45) {
        canvas.drawRRect(
          rrect,
          glowPaint,
        );
      }

      // ----------------------------------------------------------
      // MAIN THIN LINE
      // ----------------------------------------------------------

      canvas.drawRRect(
        rrect,
        barPaint,
      );
    }
  }

  @override
  bool shouldRepaint(
    covariant _WaveformPainter oldDelegate,
  ) {
    if (oldDelegate.amplitudes.length !=
        amplitudes.length) {
      return true;
    }

    for (int i = 0;
        i < amplitudes.length;
        i++) {
      if (oldDelegate.amplitudes[i] !=
          amplitudes[i]) {
        return true;
      }
    }

    return false;
  }
}