import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

class LiveRoomScreen extends StatefulWidget {
  const LiveRoomScreen({super.key});

  @override
  State<LiveRoomScreen> createState() => _LiveRoomScreenState();
}

class _LiveRoomScreenState extends State<LiveRoomScreen> {

  CameraController? cameraController;
  Timer? liveTimer;

  DateTime liveStarted = DateTime.now();

  String get liveDuration {
    final difference =
        DateTime.now().difference(liveStarted);

    final minutes = difference.inMinutes
        .toString()
        .padLeft(2, '0');

    final seconds = (difference.inSeconds % 60)
        .toString()
        .padLeft(2, '0');

    return "$minutes:$seconds";
  }


  @override
  void initState() {
    super.initState();

    setupCamera();

    liveTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (mounted) {
          setState(() {});
        }
      },
    );
  }


  Future<void> setupCamera() async {

    final cameras = await availableCameras();

    cameraController = CameraController(
      cameras.first,
      ResolutionPreset.high,
    );

    await cameraController!.initialize();

    if (mounted) {
      setState(() {});
    }
  }


  @override
  void dispose() {

    liveTimer?.cancel();

    cameraController?.dispose();

    super.dispose();
  }


  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: Colors.black,

      body: Stack(

        children: [

          // CAMERA PREVIEW
          SizedBox.expand(

            child: cameraController != null &&
                    cameraController!.value.isInitialized

                ? CameraPreview(cameraController!)

                : const Center(

                    child: CircularProgressIndicator(
                      color: Color(0xff8A3DFF),
                    ),

                  ),

          ),


          // TOP BAR
          SafeArea(

            child: Padding(

              padding: const EdgeInsets.all(18),

              child: Row(

                children: [

                  const CircleAvatar(

                    radius: 24,

                    backgroundColor:
                        Color(0xff8A3DFF),

                    child: Icon(
                      Icons.person,
                      color: Colors.white,
                    ),

                  ),


                  const SizedBox(width: 12),


                  Column(

                    crossAxisAlignment:
                        CrossAxisAlignment.start,

                    children: [

                      const Text(

                        "ChattªX User",

                        style: TextStyle(

                          color: Colors.white,

                          fontSize: 16,

                          fontWeight:
                              FontWeight.bold,

                        ),

                      ),


                      Container(

                        padding:
                            const EdgeInsets.symmetric(

                          horizontal: 10,

                          vertical: 3,

                        ),

                        decoration: BoxDecoration(

                          color: Colors.red,

                          borderRadius:
                              BorderRadius.circular(20),

                        ),

                        child: const Text(

                          "LIVE",

                          style: TextStyle(

                            color: Colors.white,

                            fontSize: 12,

                            fontWeight:
                                FontWeight.bold,

                          ),

                        ),

                      ),


                      const SizedBox(height: 4),


                      Text(

                        liveDuration,

                        style: const TextStyle(

                          color: Colors.white70,

                          fontSize: 12,

                        ),

                      ),

                    ],

                  ),


                  const Spacer(),


                  GestureDetector(

                    onTap: () {

                      Navigator.pop(context);

                    },

                    child: Container(

                      padding:
                          const EdgeInsets.symmetric(

                        horizontal: 14,

                        vertical: 8,

                      ),

                      decoration: BoxDecoration(

                        color: Colors.red,

                        borderRadius:
                            BorderRadius.circular(20),

                      ),

                      child: const Text(

                        "END",

                        style: TextStyle(

                          color: Colors.white,

                          fontWeight:
                              FontWeight.bold,

                        ),

                      ),

                    ),

                  ),

                ],

              ),

            ),

          ),


          // VIEWERS
          Positioned(

            top: 110,

            right: 20,

            child: Container(

              padding:
                  const EdgeInsets.all(10),

              decoration: BoxDecoration(

                color:
                    Colors.black.withValues(alpha: .5),

                borderRadius:
                    BorderRadius.circular(20),

              ),

              child: const Row(

                children: [

                  Icon(

                    Icons.remove_red_eye,

                    color: Colors.white,

                    size: 18,

                  ),

                  SizedBox(width: 6),

                  Text(

                    "0",

                    style: TextStyle(

                      color: Colors.white,

                    ),

                  ),

                ],

              ),

            ),

          ),


          // BOTTOM CONTROLS
          Positioned(

            bottom: 25,

            left: 20,

            right: 20,

            child: Row(

              children: [

                Expanded(

                  child: Container(

                    height: 50,

                    padding:
                        const EdgeInsets.symmetric(

                      horizontal: 15,

                    ),

                    decoration: BoxDecoration(

                      color:
                          Colors.black.withValues(alpha: .45),

                      borderRadius:
                          BorderRadius.circular(25),

                    ),

                    alignment:
                        Alignment.centerLeft,

                    child: const Text(

                      "Add comment...",

                      style: TextStyle(

                        color: Colors.white70,

                      ),

                    ),

                  ),

                ),


                const SizedBox(width: 12),


                _actionButton(
                  Icons.favorite,
                ),

                const SizedBox(width: 10),


                _actionButton(
                  Icons.share,
                ),

              ],

            ),

          ),

        ],

      ),

    );

  }


  Widget _actionButton(IconData icon) {

    return Container(

      height: 50,

      width: 50,

      decoration: BoxDecoration(

        shape: BoxShape.circle,

        color:
            const Color(0xff8A3DFF),

      ),

      child: Icon(

        icon,

        color: Colors.white,

      ),

    );

  }

}