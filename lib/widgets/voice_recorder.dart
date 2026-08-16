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
  // RECORDER
  // ============================================================

  final AudioRecorder recorder = AudioRecorder();

  Timer? amplitudeTimer;

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

  /// Real microphone amplitude samples.
  ///
  /// Each value comes from recorder.getAmplitude().
  final List<double> _rawAmplitudes = [];

  /// Final compressed waveform.
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

  int get _durationSeconds {
    return _recordingStopwatch.elapsed.inSeconds;
  }

  // ============================================================
  // START RECORDING
  // ============================================================

  Future<void> startRecording() async {
    try {
      final permission = await recorder.hasPermission();

      if (!permission) {
        debugPrint(
          'ChattªX microphone permission denied.',
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Microphone permission is required.',
              ),
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
      debugPrint(
        'ChattªX start recording error: $e',
      );
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

            normalized = ((db + 60.0) / 60.0)
                .clamp(0.0, 1.0)
                .toDouble();
          }

          // ------------------------------------------------------
          // REAL SILENCE / NOISE FLOOR
          // ------------------------------------------------------

          if (normalized < 0.08) {
            normalized = 0.0;
          }

          // ------------------------------------------------------
          // CONTRAST
          // ------------------------------------------------------

          if (normalized > 0.0) {
            normalized = math
                .pow(normalized, 0.72)
                .toDouble()
                .clamp(0.0, 1.0);
          }

          /*
           * This sample belongs to the actual recording.
           *
           * No:
           *   sin()
           *   random()
           *   fake waveform
           */

          _rawAmplitudes.add(normalized);

          /*
           * Keep memory bounded during extremely long recordings.
           * At 60ms this still represents several minutes of data.
           */
          if (_rawAmplitudes.length > 10000) {
            _rawAmplitudes.removeAt(0);
          }

          setState(() {
            currentAmplitude = normalized;
          });
        } catch (e) {
          debugPrint(
            'ChattªX amplitude capture error: $e',
          );
        }
      },
    );
  }

  // ============================================================
  // DURATION REFRESH
  // ============================================================

  void _startDurationRefresh() {
    Timer.periodic(
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
      debugPrint(
        'ChattªX pause/resume error: $e',
      );
    }
  }

  // ============================================================
  // STOP RECORDING
  // ============================================================

  Future<void> stopRecording() async {
    if (!recording) return;

    try {
      amplitudeTimer?.cancel();

      _recordingStopwatch.stop();

      final path = await recorder.stop();

      if (path == null || path.isEmpty) {
        debugPrint(
          'ChattªX recorder returned no audio path.',
        );
        return;
      }

      // --------------------------------------------------------
      // GENERATE REAL WAVEFORM
      // --------------------------------------------------------

      final generatedWaveform = _compressWaveform(
        _rawAmplitudes,
        waveformBars,
      );

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

      debugPrint(
        '==========================================',
      );
      debugPrint(
        'ChattªX VOICE RECORDING COMPLETE',
      );
      debugPrint(
        'Duration: ${actualDuration}s',
      );
      debugPrint(
        'Raw samples: ${_rawAmplitudes.length}',
      );
      debugPrint(
        'Waveform bars: ${waveform.length}',
      );
      debugPrint(
        'Frozen: $frozen',
      );
      debugPrint(
        '==========================================',
      );
    } catch (e) {
      debugPrint(
        'ChattªX stop recording error: $e',
      );
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
      return List<double>.filled(
        targetBars,
        0.0,
      );
    }

    final result = <double>[];

    for (int bar = 0; bar < targetBars; bar++) {
      final start = ((bar / targetBars) * samples.length)
          .floor();

      final end = (((bar + 1) / targetBars) *
              samples.length)
          .ceil();

      final safeStart =
          start.clamp(0, samples.length - 1);

      final safeEnd = end.clamp(
        safeStart + 1,
        samples.length,
      );

      final section = samples.sublist(
        safeStart,
        safeEnd,
      );

      if (section.isEmpty) {
        result.add(0.0);
        continue;
      }

      // --------------------------------------------------------
      // RMS
      // --------------------------------------------------------

      double sumSquares = 0.0;

      for (final value in section) {
        sumSquares += value * value;
      }

      final rms = math.sqrt(
        sumSquares / section.length,
      );

      // --------------------------------------------------------
      // PEAK
      // --------------------------------------------------------

      double peak = 0.0;

      for (final value in section) {
        if (value > peak) {
          peak = value;
        }
      }

      // --------------------------------------------------------
      // COMBINE RMS + PEAK
      // --------------------------------------------------------

      double value =
          (rms * 0.72) +
          (peak * 0.28);

      // --------------------------------------------------------
      // INTENTIONAL SILENCE
      // --------------------------------------------------------

      if (value < 0.055) {
        value = 0.0;
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
  // ============================================================

  /*
   * The actual frozen-message interaction will happen inside
   * MessageBubble.
   *
   * This state exists so the recorder is already prepared for
   * voice-note freezing without changing the audio itself.
   *
   * IMPORTANT:
   *
   * Freezing a voice note does NOT alter:
   *
   *   - audio file
   *   - waveform
   *   - duration
   *
   * MessageBubble will simply store/use:
   *
   *   isFrozen
   *
   * for the voice message.
   */

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

    if (recordedPath == null) {
      return;
    }

    final duration = _durationSeconds;

    /*
     * The exact waveform belonging to this recording
     * is sent with it.
     */

    widget.onSend(
      recordedPath!,
      duration,
      List<double>.from(waveform),
    );
  }

  // ============================================================
  // LIVE WAVEFORM
  // ============================================================

  Widget _buildLiveWaveform() {
    const int visibleBars = 24;

    final List<double> visibleSamples =
        _rawAmplitudes.length > visibleBars
            ? _rawAmplitudes.sublist(
                _rawAmplitudes.length - visibleBars,
              )
            : List<double>.from(
                _rawAmplitudes,
              );

    final List<double> bars =
        List<double>.filled(
      visibleBars,
      0.0,
    );

    final offset =
        visibleBars - visibleSamples.length;

    for (int i = 0;
        i < visibleSamples.length;
        i++) {
      bars[offset + i] =
          visibleSamples[i];
    }

    return Row(
      mainAxisAlignment:
          MainAxisAlignment.center,
      crossAxisAlignment:
          CrossAxisAlignment.center,
      children: List.generate(
        bars.length,
        (index) {
          final amplitude =
              bars[index];

          final height =
              amplitude <= 0.01
                  ? 2.0
                  : 5.0 +
                      (amplitude * 38.0);

          return AnimatedContainer(
            duration:
                const Duration(
              milliseconds: 90,
            ),
            margin:
                const EdgeInsets.symmetric(
              horizontal: 1.5,
            ),
            width: 3,
            height: height,
            decoration:
                BoxDecoration(
              gradient:
                  const LinearGradient(
                begin:
                    Alignment.topCenter,
                end:
                    Alignment.bottomCenter,
                colors: [
                  Color(0xFFB026FF),
                  Color(0xFF00E5FF),
                ],
              ),
              borderRadius:
                  BorderRadius.circular(
                10,
              ),
              boxShadow:
                  amplitude > 0.55
                      ? const [
                          BoxShadow(
                            color:
                                Color(0x5500E5FF),
                            blurRadius: 7,
                          ),
                        ]
                      : null,
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // PREVIEW WAVEFORM
  // ============================================================

  Widget _buildPreviewWaveform() {
    if (waveform.isEmpty) {
      return const SizedBox(
        height: 45,
      );
    }

    return Row(
      mainAxisAlignment:
          MainAxisAlignment.center,
      crossAxisAlignment:
          CrossAxisAlignment.center,
      children: waveform.map(
        (amplitude) {
          final height =
              amplitude <= 0.01
                  ? 2.0
                  : 5.0 +
                      (amplitude * 38.0);

          return Container(
            margin:
                const EdgeInsets.symmetric(
              horizontal: 1.5,
            ),
            width: 3,
            height: height,
            decoration:
                BoxDecoration(
              gradient:
                  const LinearGradient(
                begin:
                    Alignment.topCenter,
                end:
                    Alignment.bottomCenter,
                colors: [
                  Color(0xFFB026FF),
                  Color(0xFF00E5FF),
                ],
              ),
              borderRadius:
                  BorderRadius.circular(
                10,
              ),
              boxShadow:
                  amplitude > 0.55
                      ? const [
                          BoxShadow(
                            color:
                                Color(0x4400E5FF),
                            blurRadius: 6,
                          ),
                        ]
                      : null,
            ),
          );
        },
      ).toList(),
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
    final duration =
        _formatSeconds(_durationSeconds);

    return Container(
      height: 78,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 8,
      ),
      decoration:
          const BoxDecoration(
        color: Color(0xFF0D0D18),
      ),
      child: Row(
        children: [
          // ======================================================
          // DELETE
          // ======================================================

          GestureDetector(
            onTap: cancelRecording,
            child: Container(
              width: 42,
              height: 42,
              decoration:
                  BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(
                  0xFFFF496C,
                ).withValues(
                  alpha: .10,
                ),
                border: Border.all(
                  color: const Color(
                    0xFFFF496C,
                  ).withValues(
                    alpha: .35,
                  ),
                ),
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: Color(0xFFFF6684),
                size: 21,
              ),
            ),
          ),

          const SizedBox(width: 7),

          // ======================================================
          // WAVEFORM
          // ======================================================

          Expanded(
            child: preview
                ? _buildPreviewWaveform()
                : _buildLiveWaveform(),
          ),

          const SizedBox(width: 5),

          // ======================================================
          // DURATION
          // ======================================================

          Text(
            duration,
            style:
                const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight:
                  FontWeight.w700,
            ),
          ),

          const SizedBox(width: 3),

          // ======================================================
          // PAUSE / RESUME
          // ======================================================

          if (!preview)
            GestureDetector(
              onTap: pauseRecording,
              child: Container(
                width: 40,
                height: 40,
                decoration:
                    BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      const Color(
                    0xFF00E5FF,
                  ).withValues(
                    alpha: .08,
                  ),
                  border:
                      Border.all(
                    color:
                        const Color(
                      0xFF00E5FF,
                    ).withValues(
                      alpha: .30,
                    ),
                  ),
                ),
                child: Icon(
                  paused
                      ? Icons
                          .play_arrow_rounded
                      : Icons
                          .pause_rounded,
                  color:
                      const Color(
                    0xFF00E5FF,
                  ),
                  size: 21,
                ),
              ),
            ),

          // ======================================================
          // FREEZE
          //
          // Available in preview.
          //
          // The actual frozen voice-note behavior will be handled
          // by MessageBubble after the message is sent.
          // ======================================================

          if (preview) ...[
            const SizedBox(width: 5),

            GestureDetector(
              onTap: toggleFreeze,
              child: AnimatedContainer(
                duration:
                    const Duration(
                  milliseconds: 180,
                ),
                width: 40,
                height: 40,
                decoration:
                    BoxDecoration(
                  shape: BoxShape.circle,
                  color: frozen
                      ? const Color(
                          0xFF00E5FF,
                        ).withValues(
                          alpha: .16,
                        )
                      : const Color(
                          0xFFB026FF,
                        ).withValues(
                          alpha: .10,
                        ),
                  border:
                      Border.all(
                    color: frozen
                        ? const Color(
                            0xFF00E5FF,
                          )
                        : const Color(
                            0xFFB026FF,
                          ).withValues(
                            alpha: .45,
                          ),
                  ),
                  boxShadow: frozen
                      ? const [
                          BoxShadow(
                            color:
                                Color(
                              0x4400E5FF,
                            ),
                            blurRadius: 10,
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  frozen
                      ? Icons.lock_rounded
                      : Icons.ac_unit_rounded,
                  color: frozen
                      ? const Color(
                          0xFF00E5FF,
                        )
                      : const Color(
                          0xFFC78CFF,
                        ),
                  size: 19,
                ),
              ),
            ),
          ],

          const SizedBox(width: 5),

          // ======================================================
          // STOP / SEND
          // ======================================================

          GestureDetector(
            onTap: sendRecording,
            child: Container(
              width: 44,
              height: 44,
              decoration:
                  BoxDecoration(
                shape: BoxShape.circle,
                gradient:
                    const LinearGradient(
                  begin:
                      Alignment.topLeft,
                  end:
                      Alignment.bottomRight,
                  colors: [
                    Color(0xFFB026FF),
                    Color(0xFF6C2BFF),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        const Color(
                      0xFFB026FF,
                    ).withValues(
                      alpha: .30,
                    ),
                    blurRadius: 13,
                  ),
                ],
              ),
              child: Icon(
                preview
                    ? Icons
                        .send_rounded
                    : Icons
                        .stop_rounded,
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

    _recordingStopwatch.stop();

    pulseController.dispose();

    recorder.dispose();

    super.dispose();
  }
}